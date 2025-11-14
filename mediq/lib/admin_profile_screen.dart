import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'main.dart';
import 'admin_drawer.dart';
import 'login_page.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  // --- Firebase Instances ---
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  // --- Controllers for Form Fields ---
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nicController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();

  // --- State Variables ---
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _profileImageUrl;
  DateTime? _createdAt;
  String _role = '';
  
  // Email change state
  User? _currentUser;
  late StreamSubscription<User?> _authStateSubscription;
  bool _showEmailChangePopup = false;
  bool _showVerificationSuccessPopup = false;

  // Local picked image file
  File? _pickedImageFile;

  @override
  void initState() {
    super.initState();
    
    _authStateSubscription = _auth.authStateChanges().listen((user) {
      if (user != null) {
        user.reload().then((_) {
          if (mounted) {
            final reloadedUser = _auth.currentUser;
            
            // Check if verification just completed
            if (reloadedUser != null && reloadedUser.emailVerified && _currentUser?.emailVerified == false) {
              // Show success popup
              setState(() {
                _showVerificationSuccessPopup = true;
              });
              
              // Auto hide success popup after 4 seconds
              Future.delayed(const Duration(seconds: 4), () {
                if (mounted) {
                  setState(() {
                    _showVerificationSuccessPopup = false;
                  });
                }
              });
              
              _loadUserProfile();
            }

            setState(() {
              _currentUser = reloadedUser;
            });
          }
        });
      }
    });

    _loadUserProfile();
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    _fullNameController.dispose();
    _emailController.dispose();
    _nicController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  // --- Data Loading and Initialization ---
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
      _currentUser = user;
      
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
      _emailController.text = (user.email ?? data['email'] ?? '') as String;
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

  // --- Image Handling ---
  void _openImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera, color: Color(0xFF8D78F9)),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF8D78F9)),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty || _pickedImageFile != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Remove Current Photo', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _removeProfileImage();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close, color: Color(0xFF8D78F9)),
                title: const Text('Cancel'),
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      },
    );
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

  Future<void> _removeProfileImage() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _profileImageUrl = null;
      _pickedImageFile = null;
    });

    try {
      final ref = _storage.ref().child('profile_images').child('${user.uid}.jpg');
      await ref.delete().catchError((e) {
        if (e is! FirebaseException || e.code != 'object-not-found') {
          debugPrint('Storage deletion error: $e');
        }
      });

      await _firestore.collection('users').doc(user.uid).update({
        'profileImage': FieldValue.delete(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo removed')),
      );
    } catch (e) {
      await _loadUserProfile();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove photo: ${e.toString()}')),
      );
    }
  }

  // --- Profile Save Logic ---
  Future<void> _saveProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _error = 'No authenticated user found.';
      });
      return;
    }

    final fullName = _fullNameController.text.trim();
    final newEmail = _emailController.text.trim();
    final nic = _nicController.text.trim();
    final mobile = _mobileController.text.trim();

    if (fullName.isEmpty || newEmail.isEmpty) {
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

      final updateData = <String, dynamic>{
        'fullName': fullName,
        'email': newEmail,
        'nic': nic,
        'mobileNumber': mobile,
      };
      
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        updateData['profileImage'] = uploadedUrl;
      } else if (_profileImageUrl == null && _pickedImageFile == null) {
        updateData['profileImage'] = FieldValue.delete();
      }

      await _firestore.collection('users').doc(user.uid).update(updateData);

      // Show email change popup if email is changed
      if (newEmail != user.email) {
        try {
          await user.verifyBeforeUpdateEmail(newEmail);
          
          // Show email change popup
          setState(() {
            _showEmailChangePopup = true;
          });
          
          // Auto hide popup after 6 seconds
          Future.delayed(const Duration(seconds: 6), () {
            if (mounted) {
              setState(() {
                _showEmailChangePopup = false;
              });
            }
          });

        } on FirebaseAuthException catch (e) {
          debugPrint('Auth email update failed: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Profile updated but email change failed: ${e.code}'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }

      await _loadUserProfile();
      setState(() {
        _pickedImageFile = null;
      });

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

  // --- Popup Widgets ---
  Widget _buildEmailChangePopup() {
    if (!_showEmailChangePopup) return const SizedBox.shrink();

    return Container(
      color: Colors.black54,
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.email_outlined, size: 50, color: Color(0xFF8D78F9)),
              const SizedBox(height: 16),
              const Text(
                'Email Change Initiated',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please check your inbox to verify the new email. All profile actions are temporarily disabled until verification is complete.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showEmailChangePopup = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8D78F9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationSuccessPopup() {
    if (!_showVerificationSuccessPopup) return const SizedBox.shrink();

    return Container(
      color: Colors.black54,
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified, size: 50, color: Colors.green),
              const SizedBox(height: 16),
              const Text(
                'Email Verified Successfully!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your email has been verified successfully. All profile actions are now re-enabled.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper: Styled Text Field Widget ---
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      style: TextStyle(color: enabled ? AppColors.darkText : Colors.grey.shade600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.inputBorder.withOpacity(0.8)),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF8D78F9), width: 2)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
    );
  }
  
  // --- Helper: Verification Status Widget ---
  Widget _buildVerificationStatusWidget(bool isPending) {
    if (!isPending) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Action Disabled: Email Verification Pending',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                SizedBox(height: 4),
                Text(
                  'Please check your inbox for the verification link. All profile editing actions are temporarily locked until the email is confirmed.',
                  style: TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // --- Logout Function ---
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

  // --- Helper: Format Account Creation Date ---
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

    final bool isVerificationPending = _currentUser?.emailVerified == false && user != null;
    final bool disableFieldsAndButton = isVerificationPending || _saving;

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
      body: Stack(
        children: [
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF8D78F9)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Header Card ---
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
                                color: const Color(0xFF8D78F9).withOpacity(0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: isVerificationPending ? null : _openImageOptions,
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
                                          ? const Icon(Icons.person, size: 40, color: Color(0xFF8D78F9))
                                          : null,
                                    ),
                                    if (!isVerificationPending)
                                      Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: const Icon(Icons.camera_alt, size: 18, color: Color(0xFF8D78F9)),
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
                        _buildVerificationStatusWidget(isVerificationPending), 
                        
                        // --- Profile Details Section ---
                        const Text('Manage Profile Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 18),

                        const Text('Profile Picture', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF8D78F9))),
                        const SizedBox(height: 8),

                        GestureDetector(
                          onTap: isVerificationPending ? null : _openImageOptions,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isVerificationPending ? Colors.grey.shade100 : const Color(0xFF8D78F9),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: isVerificationPending ? Colors.grey.shade300 : const Color(0xFF8D78F9)),
                            ),
                            child: Center(
                              child: Text(
                                isVerificationPending ? 'Image Change Disabled (Verification Pending)' : (_pickedImageFile != null ? 'Image Selected (Tap to Change)' : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty ? 'Change Image (Tap to Change)' : 'Click To Choose Image..')),
                                style: TextStyle(fontSize: 14, color: isVerificationPending ? Colors.grey.shade500 : Colors.white),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),
                        const Text('Full Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        _buildTextField(controller: _fullNameController, hint: 'Full Name', enabled: !isVerificationPending),

                        const SizedBox(height: 12),
                        const Text('Email', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        _buildTextField(controller: _emailController, hint: 'Email', keyboardType: TextInputType.emailAddress, enabled: !isVerificationPending),

                        const SizedBox(height: 12),
                        const Text('NIC', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        _buildTextField(controller: _nicController, hint: 'NIC', enabled: !isVerificationPending),

                        const SizedBox(height: 12),
                        const Text('Mobile Number', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        _buildTextField(controller: _mobileController, hint: 'Mobile Number', keyboardType: TextInputType.phone, enabled: !isVerificationPending),

                        const SizedBox(height: 24),
                        Center(
                          child: SizedBox(
                            width: 140,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                backgroundColor: const Color(0xFF8D78F9),
                                elevation: 4,
                                shadowColor: const Color(0xFF8D78F9).withOpacity(0.3),
                              ),
                              onPressed: disableFieldsAndButton ? null : _saveProfile,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: _saving
                                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Text('Update', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),
                        Padding(
                          padding: const EdgeInsets.only(left: 6.0),
                          child: Text(
                              'Account CreatedAt : ${_formatCreatedAt()}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkText)),
                        ),

                        const SizedBox(height: 30),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text('Error: $_error', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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

          // Popups
          if (_showEmailChangePopup) _buildEmailChangePopup(),
          if (_showVerificationSuccessPopup) _buildVerificationSuccessPopup(),
        ],
      ),
    );
  }
}