import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import 'admin_drawer.dart';
import '../auth/login_page.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  // --- Firebase Instances ---
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _imagePicker = ImagePicker();

  // --- Controllers for Form Fields ---
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nicController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();

  // --- State Variables ---
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _profileImageBase64;
  DateTime? _createdAt;
  String _role = '';
  
  // Auth state management
  User? _currentUser;
  late StreamSubscription<User?> _authStateSubscription;
  bool _showEmailChangePopup = false;
  bool _showVerificationSuccessPopup = false;

  // Image handling
  File? _pickedImageFile;
  bool _uploadingImage = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _initializeAuthListener();
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

  // --- Initialization Methods ---
  void _initializeAuthListener() {
    _authStateSubscription = _auth.authStateChanges().listen((user) {
      if (user != null) {
        user.reload().then((_) {
          if (!mounted) return;
          
          final reloadedUser = _auth.currentUser;
          _handleAuthStateChange(reloadedUser);
        });
      }
    });
  }

  void _handleAuthStateChange(User? reloadedUser) {
    final justVerified = reloadedUser != null && 
                        reloadedUser.emailVerified && 
                        _currentUser?.emailVerified == false;
    
    setState(() {
      _currentUser = reloadedUser;
    });

    if (justVerified) {
      setState(() {
        _showVerificationSuccessPopup = true;
      });
      
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _showVerificationSuccessPopup = false;
          });
        }
      });
      
      _loadUserProfile();
    }
  }

  // --- Data Loading Methods ---
  Future<void> _loadUserProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final user = _auth.currentUser;
    if (user == null) {
      _setError('No authenticated user found.');
      return;
    }

    try {
      _currentUser = user;
      
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        _setError('User profile not found in Firestore.');
        return;
      }

      await _updateLocalStateFromDocument(doc);
    } catch (e) {
      _setError('Failed to load profile: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _setError(String error) {
    if (mounted) {
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _updateLocalStateFromDocument(DocumentSnapshot doc) async {
    final data = doc.data()! as Map<String, dynamic>;
    
    _fullNameController.text = (data['fullName'] ?? '') as String;
    _emailController.text = (_currentUser?.email ?? data['email'] ?? '') as String;
    _nicController.text = (data['nic'] ?? '') as String;
    _mobileController.text = (data['mobileNumber'] ?? '') as String;
    
    // FIXED: Use 'profileImage' instead of 'profileImageBase64'
    _profileImageBase64 = (data['profileImage'] ?? '') as String?;
    
    _role = (data['role'] ?? '') as String;

    final ts = data['createdAt'];
    if (ts is Timestamp) {
      _createdAt = ts.toDate();
    } else if (ts is DateTime) {
      _createdAt = ts;
    } else {
      _createdAt = null;
    }

    _initializeChangeTracking();
  }

  void _initializeChangeTracking() {
    _fullNameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _nicController.addListener(_onFieldChanged);
    _mobileController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  // --- Image Handling Methods ---
  void _openImageOptions() {
    if (_isVerificationPending) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              _buildImageOptionTile(
                icon: Icons.photo_camera,
                title: 'Take Photo',
                onTap: () => _pickImage(ImageSource.camera),
              ),
              _buildImageOptionTile(
                icon: Icons.photo_library,
                title: 'Choose from Gallery',
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              if (_hasExistingImage)
                _buildImageOptionTile(
                  icon: Icons.delete_outline,
                  title: 'Remove Current Photo',
                  isDestructive: true,
                  onTap: _confirmRemoveImage,
                ),
              _buildImageOptionTile(
                icon: Icons.close,
                title: 'Cancel',
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : const Color(0xFF8D78F9)),
      title: Text(title, style: TextStyle(color: isDestructive ? Colors.red : null)),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 400,  // Reduced for better performance
        maxHeight: 400, // Reduced for better performance
        imageQuality: 60, // Reduced quality for smaller file size
      );
      if (picked == null) return;

      setState(() {
        _pickedImageFile = File(picked.path);
        _hasUnsavedChanges = true;
      });

    } catch (e) {
      _showSnackBar('Image pick failed: ${e.toString()}');
    }
  }

  Future<void> _confirmRemoveImage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Profile Photo'),
        content: const Text('Are you sure you want to remove your profile photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _removeProfileImage();
    }
  }

  Future<void> _removeProfileImage() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _uploadingImage = true;
    });

    try {
      // FIXED: Use 'profileImage' instead of 'profileImageBase64'
      await _firestore.collection('users').doc(user.uid).update({
        'profileImage': FieldValue.delete(),
      });

      setState(() {
        _profileImageBase64 = null;
        _pickedImageFile = null;
        _uploadingImage = false;
        _hasUnsavedChanges = true;
      });

      _showSnackBar('Profile photo removed');
    } catch (e) {
      setState(() {
        _uploadingImage = false;
      });
      _showSnackBar('Failed to remove photo: ${e.toString()}');
    }
  }

  // FIXED: Improved Image Processing Function
  Future<String?> _processAndEncodeImage(File file) async {
    try {
      debugPrint('🔄 Starting image processing...');
      
      if (!await file.exists()) {
        debugPrint('❌ File does not exist at path: ${file.path}');
        return null;
      }

      // Get file info
      final fileStat = await file.stat();
      debugPrint('📁 File size: ${fileStat.size} bytes');
      debugPrint('📁 File path: ${file.path}');

      // Read file as bytes
      final bytes = await file.readAsBytes();
      debugPrint('📊 Original image size: ${bytes.length} bytes');

      // Check if file is too large (max 500KB for base64)
      if (bytes.length > 500000) {
        debugPrint('⚠️ Image too large: ${bytes.length} bytes. Max allowed: 500000 bytes');
        _showSnackBar('Image is too large. Please choose a smaller image.');
        return null;
      }

      // Convert to base64
      final base64String = base64Encode(bytes);
      debugPrint('✅ Base64 encoding successful');
      debugPrint('📐 Base64 string length: ${base64String.length} characters');

      return base64String;
    } catch (e) {
      debugPrint('❌ Image processing error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      _showSnackBar('Failed to process image: ${e.toString()}');
      return null;
    }
  }

  // --- Profile Save Logic ---
  Future<void> _saveProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      _setError('No authenticated user found.');
      return;
    }

    final fullName = _fullNameController.text.trim();
    final newEmail = _emailController.text.trim();
    final nic = _nicController.text.trim();
    final mobile = _mobileController.text.trim();

    if (fullName.isEmpty || newEmail.isEmpty) {
      _setError('Full name and email are required.');
      return;
    }

    setState(() {
      _saving = true;
      _uploadingImage = true;
      _error = null;
    });

    try {
      String? encodedImage = _profileImageBase64;
      bool imageUpdated = false;

      // Process image only if a new one is picked
      if (_pickedImageFile != null) {
        debugPrint('🖼️ New image detected, starting encoding process...');
        final base64String = await _processAndEncodeImage(_pickedImageFile!);
        if (base64String != null) {
          encodedImage = base64String;
          imageUpdated = true;
          debugPrint('✅ Image encoding successful');
        } else {
          debugPrint('❌ Image encoding failed - keeping existing image');
          // Continue with existing image without showing error
        }
      }

      final updateData = <String, dynamic>{
        'fullName': fullName,
        'email': newEmail,
        'nic': nic,
        'mobileNumber': mobile,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // FIXED: Use 'profileImage' instead of 'profileImageBase64'
      if (encodedImage != null && encodedImage.isNotEmpty) {
        updateData['profileImage'] = encodedImage;
        debugPrint('💾 Will update profileImage field in Firestore');
      } else if (_profileImageBase64 == null && _pickedImageFile == null) {
        updateData['profileImage'] = FieldValue.delete();
        debugPrint('🗑️ Will remove profileImage field from Firestore');
      }

      debugPrint('🔥 Updating Firestore with profile data...');
      debugPrint('📝 Update data: $updateData');
      
      await _firestore.collection('users').doc(user.uid).update(updateData);
      debugPrint('✅ Firestore update successful');

      // Show appropriate success message
      if (newEmail != user.email) {
        await _handleEmailChange(user, newEmail);
      } else if (imageUpdated) {
        _showSnackBar('Profile updated successfully with new photo!');
      } else {
        _showSnackBar('Profile updated successfully');
      }

      // Reload profile to get latest data
      await _loadUserProfile();
      setState(() {
        _pickedImageFile = null;
        _hasUnsavedChanges = false;
      });

    } catch (e) {
      debugPrint('❌ Save profile error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      
      // More specific error handling
      if (e is FirebaseException) {
        _setError('Firestore error: ${e.code} - ${e.message}');
      } else {
        _setError('Failed to save profile: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _uploadingImage = false;
        });
      }
    }
  }

  Future<void> _handleEmailChange(User user, String newEmail) async {
    try {
      await user.verifyBeforeUpdateEmail(newEmail);
      
      setState(() {
        _showEmailChangePopup = true;
      });
      
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted) {
          setState(() {
            _showEmailChangePopup = false;
          });
        }
      });

    } on FirebaseAuthException catch (e) {
      debugPrint('Auth email update failed: $e');
      _showSnackBar(
        'Profile updated but email change failed: ${e.code}',
        duration: const Duration(seconds: 4),
      );
    }
  }

  // --- Email Verification Methods ---
  Future<void> _resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await user.sendEmailVerification();
      _showSnackBar('Verification email sent to ${user.email}');
    } catch (e) {
      _showSnackBar('Failed to send verification email: ${e.toString()}');
    }
  }

  // --- UI Helper Methods ---
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      'Please check your inbox for the verification link.',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _resendVerificationEmail,
              style: TextButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Resend Verification Email',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15), 
          borderSide: BorderSide(color: Colors.grey.shade300)
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15), 
          borderSide: const BorderSide(color: Color(0xFF8D78F9), width: 2)
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15), 
          borderSide: BorderSide(color: Colors.grey.shade200)
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        _uploadingImage
            ? Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8D78F9)),
                  ),
                ),
              )
            : CircleAvatar(
                radius: 36,
                backgroundColor: Colors.white,
                backgroundImage: _getProfileImage(),
                child: _getProfileImage() == null
                    ? Icon(Icons.person, size: 40, color: Color(0xFF8D78F9))
                    : null,
              ),
        
        if (!_uploadingImage && !_isVerificationPending)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(6),
            child: Icon(Icons.camera_alt, size: 16, color: Color(0xFF8D78F9)),
          ),
      ],
    );
  }

  Widget _buildSaveButton(bool isDisabled) {
    return SizedBox(
      width: 140,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          backgroundColor: isDisabled ? Colors.grey.shade400 : const Color(0xFF8D78F9),
          elevation: 4,
          shadowColor: const Color(0xFF8D78F9).withOpacity(0.3),
        ),
        onPressed: isDisabled ? null : _saveProfile,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: _saving
                ? SizedBox(
                    height: 18, 
                    width: 18, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_hasUnsavedChanges) 
                        Icon(Icons.save, size: 18, color: Colors.white),
                      if (_hasUnsavedChanges) SizedBox(width: 6),
                      Text(
                        _hasUnsavedChanges ? 'Save' : 'Update',
                        style: TextStyle(
                          color: Colors.white, 
                          fontSize: 16, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // --- Helper Methods ---
  ImageProvider? _getProfileImage() {
    if (_pickedImageFile != null) {
      return FileImage(_pickedImageFile!);
    } else if (_profileImageBase64 != null && _profileImageBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(_profileImageBase64!);
        return MemoryImage(bytes);
      } catch (e) {
        debugPrint('Error decoding base64 image: $e');
        return null;
      }
    }
    return null;
  }

  void _showSnackBar(String message, {Duration duration = const Duration(seconds: 3)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
        _showSnackBar('Logout failed: ${e.toString()}');
      }
    }
  }

  String _formatCreatedAt() {
    if (_createdAt == null) return '-';
    return DateFormat('yyyy-MM-dd • hh:mm a').format(_createdAt!);
  }

  // --- Computed Properties ---
  bool get _isVerificationPending => _currentUser?.emailVerified == false && _currentUser != null;
  bool get _hasExistingImage => _profileImageBase64 != null && _profileImageBase64!.isNotEmpty || _pickedImageFile != null;
  bool get _disableFieldsAndButton => _isVerificationPending || _saving;
  String get _displayName => _fullNameController.text.isNotEmpty 
      ? _fullNameController.text 
      : (_currentUser?.displayName ?? 'Administrator');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        leading: Builder(builder: (context) {
          return IconButton(
            icon: Icon(Icons.menu, color: Color(0xFF8D78F9), size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          );
        }),
        actions: [
          if (_hasUnsavedChanges)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, size: 16, color: Colors.orange.shade800),
                    SizedBox(width: 4),
                    Text(
                      'Unsaved changes',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            icon: Icon(Icons.logout, color: Color(0xFF8D78F9)),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
          SizedBox(width: 6),
        ],
      ),
      drawer: AdminDrawer(
        userName: _displayName,
        userRole: _role.isNotEmpty ? _role : 'Administrator',
        onNavTap: (title) {
          _showSnackBar('$title tapped');
        },
        onLogout: _handleLogout,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: Color(0xFF8D78F9)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                onTap: _isVerificationPending ? null : _openImageOptions,
                                child: _buildProfileImage(),
                              ),
                              SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome Back, $_displayName',
                                      style: TextStyle(
                                        fontSize: 18, 
                                        fontWeight: FontWeight.bold, 
                                        color: AppColors.darkText
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      _role.isNotEmpty ? _role : 'Administrator', 
                                      style: TextStyle(
                                        fontSize: 13.5, 
                                        color: AppColors.darkText.withOpacity(0.7)
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.notifications_none, color: AppColors.darkText, size: 24),
                            ],
                          ),
                        ),

                        SizedBox(height: 18),
                        _buildVerificationStatusWidget(_isVerificationPending), 
                        
                        Text(
                          'Manage Profile Details', 
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)
                        ),
                        SizedBox(height: 18),

                        Text(
                          'Profile Picture', 
                          style: TextStyle(
                            fontSize: 15, 
                            fontWeight: FontWeight.w600, 
                            color: Color(0xFF8D78F9)
                          ),
                        ),
                        SizedBox(height: 8),

                        GestureDetector(
                          onTap: _isVerificationPending ? null : _openImageOptions,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _isVerificationPending ? Colors.grey.shade100 : Color(0xFF8D78F9),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: _isVerificationPending ? Colors.grey.shade300 : Color(0xFF8D78F9)
                              ),
                            ),
                            child: Center(
                              child: _uploadingImage
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text('Processing Image...', style: TextStyle(color: Colors.white, fontSize: 14)),
                                      ],
                                    )
                                  : Text(
                                      _isVerificationPending 
                                          ? 'Image Change Disabled (Verification Pending)' 
                                          : (_pickedImageFile != null 
                                              ? 'Image Selected (Tap to Change)' 
                                              : (_hasExistingImage
                                                  ? 'Change Image (Tap to Change)' 
                                                  : 'Click To Choose Image..')),
                                      style: TextStyle(
                                        fontSize: 14, 
                                        color: _isVerificationPending ? Colors.grey.shade500 : Colors.white
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        SizedBox(height: 18),
                        Text('Full Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        SizedBox(height: 8),
                        _buildTextField(
                          controller: _fullNameController, 
                          hint: 'Full Name', 
                          enabled: !_isVerificationPending
                        ),

                        SizedBox(height: 12),
                        Text('Email', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        SizedBox(height: 8),
                        _buildTextField(
                          controller: _emailController, 
                          hint: 'Email', 
                          keyboardType: TextInputType.emailAddress, 
                          enabled: !_isVerificationPending
                        ),

                        SizedBox(height: 12),
                        Text('NIC', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        SizedBox(height: 8),
                        _buildTextField(
                          controller: _nicController, 
                          hint: 'NIC', 
                          enabled: !_isVerificationPending
                        ),

                        SizedBox(height: 12),
                        Text('Mobile Number', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        SizedBox(height: 8),
                        _buildTextField(
                          controller: _mobileController, 
                          hint: 'Mobile Number', 
                          keyboardType: TextInputType.phone, 
                          enabled: !_isVerificationPending
                        ),

                        SizedBox(height: 24),
                        Center(
                          child: _buildSaveButton(_disableFieldsAndButton),
                        ),

                        SizedBox(height: 18),
                        Padding(
                          padding: const EdgeInsets.only(left: 6.0),
                          child: Text(
                            'Account Created: ${_formatCreatedAt()}',
                            style: TextStyle(
                              fontSize: 13, 
                              fontWeight: FontWeight.w600, 
                              color: AppColors.darkText
                            ),
                          ),
                        ),

                        SizedBox(height: 30),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              'Error: $_error', 
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
                            ),
                          ),

                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Text(
                              'Developed By Malitha Tishamal', 
                              style: TextStyle(
                                color: AppColors.darkText.withOpacity(0.6), 
                                fontSize: 12
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          if (_showEmailChangePopup) _buildEmailChangePopup(),
          if (_showVerificationSuccessPopup) _buildVerificationSuccessPopup(),
        ],
      ),
    );
  }
}