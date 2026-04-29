// lib/pharmacist_profile_screen.dart
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../main.dart';
import 'pharmacist_drawer.dart';
import '../auth/login_page.dart';

class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA);
  static const Color lightBackground = Color(0xFFF3F0FF);
  static const Color darkText = Color(0xFF333333);
  static const Color headerGradientStart = Color.fromARGB(255, 235, 151, 225);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF333333);
  static const Color inputBorder = Color(0xFFE0E0E0);
}

class PharmacistProfileScreen extends StatefulWidget {
  const PharmacistProfileScreen({super.key});

  @override
  State<PharmacistProfileScreen> createState() =>
      _PharmacistProfileScreenState();
}

class _PharmacistProfileScreenState extends State<PharmacistProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _imagePicker = ImagePicker();

  final String _cloudName = "dqeptzlsb";
  final String _uploadPreset = "flutter_mediq_upload";

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nicController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();

  static const String _defaultProfileImageUrl =
    'https://res.cloudinary.com/dqeptzlsb/image/upload/v1776579551/pharmizist-default_weoaaq.jpg';

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _profileImageUrl;
  DateTime? _createdAt;
  String _role = '';

  User? _currentUser;
  late StreamSubscription<User?> _authStateSubscription;
  bool _showEmailChangePopup = false;
  bool _showVerificationSuccessPopup = false;

  XFile? _pickedImageFile;
  bool _uploadingImage = false;
  bool _hasUnsavedChanges = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
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
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    );
  }

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
      if (mounted) setState(() => _loading = false);
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
    _profileImageUrl = (data['profileImageUrl'] ?? '') as String?;
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
      setState(() => _hasUnsavedChanges = true);
    }
  }

  // Header - with menu button (fixed: use _displayName instead of undefined _currentUserName)
  Widget _buildDashboardHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 8, left: 20, right: 20, bottom: 16),
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
                icon: const Icon(Icons.menu, color: AppColors.headerTextDark, size: 28),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const Spacer(),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _displayName, // ✅ fixed: was _currentUserName
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.headerTextDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Logged in as: Pharmacist',
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
          const Text(
            'Profile Management',
            style: TextStyle(
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

  // ========== IMAGE PICKER WITH SQUARE CROP (1:1) ==========
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
      leading: Icon(icon, color: isDestructive ? Colors.red : AppColors.primaryPurple),
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
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;

      final croppedFile = await _cropToSquare(picked);
      if (croppedFile == null) return;

      setState(() {
        _pickedImageFile = croppedFile;
        _hasUnsavedChanges = true;
      });
    } catch (e) {
      debugPrint('Image pick error: $e');
      _showSnackBar('Failed to process image: ${e.toString()}');
    }
  }

  Future<XFile?> _cropToSquare(XFile imageFile) async {
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Adjust Profile Picture',
            toolbarColor: AppColors.primaryPurple,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
            showCropGrid: false,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
          IOSUiSettings(
            title: 'Adjust Profile Picture',
            aspectRatioLockEnabled: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
        ],
      );

      if (cropped == null) return null;
      return XFile(cropped.path);
    } catch (e) {
      debugPrint('Crop error: $e');
      _showSnackBar('Failed to adjust image');
      return null;
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

    setState(() => _uploadingImage = true);

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'profileImageUrl': _defaultProfileImageUrl,
      });

      setState(() {
        _profileImageUrl = _defaultProfileImageUrl;
        _pickedImageFile = null;
        _uploadingImage = false;
      });

      _showSnackBar('Profile photo removed. Default photo set.');
    } catch (e) {
      setState(() => _uploadingImage = false);
      _showSnackBar('Failed to remove photo: ${e.toString()}');
    }
  }

  Future<String?> _uploadImageToCloudinary(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      if (bytes.length > 1000000) {
        _showSnackBar('Image is too large. Max 1MB allowed.');
        return null;
      }

      final url = Uri.parse("https://api.cloudinary.com/v1_1/$_cloudName/image/upload");
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Upload timed out'),
      );

      final response = await http.Response.fromStream(streamedResponse);
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return responseData['secure_url'];
      } else {
        final errorMsg = responseData['error']?['message'] ?? 'Upload failed';
        _showSnackBar('Upload failed: $errorMsg');
        return null;
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      _showSnackBar('Upload failed. Please try again.');
      return null;
    }
  }

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
      String? finalProfileImageUrl = _profileImageUrl;
      bool imageUpdated = false;

      if (_pickedImageFile != null) {
        final cloudinaryUrl = await _uploadImageToCloudinary(_pickedImageFile!);
        if (cloudinaryUrl != null) {
          finalProfileImageUrl = cloudinaryUrl;
          imageUpdated = true;
        } else {
          setState(() {
            _saving = false;
            _uploadingImage = false;
          });
          return;
        }
      }

      final updateData = <String, dynamic>{
        'fullName': fullName,
        'email': newEmail,
        'nic': nic,
        'mobileNumber': mobile,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (finalProfileImageUrl != null && finalProfileImageUrl.isNotEmpty) {
        updateData['profileImageUrl'] = finalProfileImageUrl;
      } else if (_pickedImageFile == null && _profileImageUrl == null) {
        updateData['profileImageUrl'] = FieldValue.delete();
      }

      await _firestore.collection('users').doc(user.uid).update(updateData);

      if (newEmail != user.email) {
        await _handleEmailChange(user, newEmail);
      } else {
        if (imageUpdated) {
          _showSnackBar('Profile updated with new photo!');
        } else if (_pickedImageFile == null && _profileImageUrl == null) {
          _showSnackBar('Profile updated - photo removed');
        } else {
          _showSnackBar('Profile updated successfully');
        }
      }

      setState(() {
        _pickedImageFile = null;
        _hasUnsavedChanges = false;
        _profileImageUrl = finalProfileImageUrl;
      });
    } catch (e) {
      _setError('Failed to save profile: ${e.toString()}');
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
      setState(() => _showEmailChangePopup = true);
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted) setState(() => _showEmailChangePopup = false);
      });
    } on FirebaseAuthException catch (e) {
      _showSnackBar('Profile updated but email change failed: ${e.code}');
    }
  }

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
              const Icon(Icons.email_outlined, size: 50, color: AppColors.primaryPurple),
              const SizedBox(height: 16),
              const Text('Email Change Initiated', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                'Please check your inbox to verify the new email. All profile actions are temporarily disabled until verification is complete.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => setState(() => _showEmailChangePopup = false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
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
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified, size: 50, color: Colors.green),
              SizedBox(height: 16),
              Text('Email Verified Successfully!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
              SizedBox(height: 12),
              Text('Your email has been verified. All profile actions are now re-enabled.', textAlign: TextAlign.center),
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
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Action Disabled: Email Verification Pending', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    SizedBox(height: 4),
                    Text('Please check your inbox for the verification link.', style: TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _resendVerificationEmail,
              style: TextButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Resend Verification Email', style: TextStyle(color: Colors.red.shade700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      style: TextStyle(color: enabled ? Colors.black : Colors.grey.shade600),
      decoration: _inputDecoration(label: label, enabled: enabled),
    );
  }

  Widget _buildSaveButton(bool isDisabled) {
    return SizedBox(
      width: 140,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          backgroundColor: isDisabled ? Colors.grey.shade400 : AppColors.primaryPurple,
          elevation: 4,
          shadowColor: AppColors.primaryPurple.withOpacity(0.3),
        ),
        onPressed: isDisabled ? null : _saveProfile,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_hasUnsavedChanges) const Icon(Icons.save, size: 18, color: Colors.white),
                      if (_hasUnsavedChanges) const SizedBox(width: 6),
                      Text(_hasUnsavedChanges ? 'Save' : 'Update', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return GestureDetector(
      onTap: _isVerificationPending ? null : _openImageOptions,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _isVerificationPending ? Colors.grey.shade300 : AppColors.inputBorder, width: 1.5),
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: _getProfileImage() != null
                        ? DecorationImage(image: _getProfileImage()!, fit: BoxFit.cover)
                        : null,
                    gradient: _getProfileImage() == null
                        ? const LinearGradient(colors: [Color(0xFF2764E7), Color(0xFF457AED)])
                        : null,
                    border: Border.all(color: _getProfileImage() == null ? Colors.transparent : AppColors.primaryPurple, width: 2),
                    boxShadow: [BoxShadow(color: AppColors.primaryPurple.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: _getProfileImage() == null ? const Icon(Icons.person, size: 60, color: Colors.white) : null,
                ),
                if (_uploadingImage)
                  Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _uploadingImage
                  ? 'Uploading to Cloudinary...'
                  : _isVerificationPending
                      ? 'Image Change Disabled (Verification Pending)'
                      : (_pickedImageFile != null ? 'Tap to Change Image' : (_hasExistingImage ? 'Tap to Change Image' : 'Tap to Add Image')),
              style: TextStyle(
                fontSize: 14,
                color: _uploadingImage
                    ? AppColors.primaryPurple
                    : (_isVerificationPending ? Colors.grey.shade500 : AppColors.primaryPurple),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider? _getProfileImage() {
    if (_pickedImageFile != null) return FileImage(File(_pickedImageFile!.path));
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) return NetworkImage(_profileImageUrl!);
    return null;
  }

  void _showSnackBar(String message, {Duration duration = const Duration(seconds: 3)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: duration, behavior: SnackBarBehavior.floating),
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
      if (mounted) _showSnackBar('Logout failed: ${e.toString()}');
    }
  }

  String _formatCreatedAt() {
    if (_createdAt == null) return '-';
    return DateFormat('yyyy-MM-dd • hh:mm a').format(_createdAt!);
  }

  bool get _isVerificationPending => _currentUser?.emailVerified == false && _currentUser != null;
  bool get _hasExistingImage => (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) || _pickedImageFile != null;
  bool get _disableFieldsAndButton => _isVerificationPending || _saving;
  String get _displayName => _fullNameController.text.isNotEmpty
      ? _fullNameController.text
      : (_currentUser?.displayName ?? 'Pharmacist');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightBackground,
      drawer: PharmacistDrawer(
        userName: _displayName,
        userRole: _role.isNotEmpty ? _role : 'Pharmacist',
        profileImageUrl: _profileImageUrl,
        onNavTap: (title) => _showSnackBar('$title tapped'),
        onLogout: _handleLogout,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildDashboardHeader(context),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 10),
                              _buildVerificationStatusWidget(_isVerificationPending),
                              const Text('Manage Profile Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 18),
                              const Text('Profile Picture', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryPurple)),
                              const SizedBox(height: 8),
                              _buildImagePreview(),
                              const SizedBox(height: 18),
                              _buildTextField(controller: _fullNameController, label: 'Full Name', enabled: !_isVerificationPending),
                              const SizedBox(height: 12),
                              _buildTextField(controller: _emailController, label: 'Email', keyboardType: TextInputType.emailAddress, enabled: !_isVerificationPending),
                              const SizedBox(height: 12),
                              _buildTextField(controller: _nicController, label: 'NIC', enabled: !_isVerificationPending),
                              const SizedBox(height: 12),
                              _buildTextField(controller: _mobileController, label: 'Mobile Number', keyboardType: TextInputType.phone, enabled: !_isVerificationPending),
                              const SizedBox(height: 24),
                              Center(child: _buildSaveButton(_disableFieldsAndButton)),
                              const SizedBox(height: 18),
                              Padding(
                                padding: const EdgeInsets.only(left: 6.0),
                                child: Text('Account Created: ${_formatCreatedAt()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
                              ),
                              const SizedBox(height: 30),
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Text('Error: $_error', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                ),
                              const SizedBox(height: 50),
                            ],
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
              child: const Text('Developed By Malitha Tishamal', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
            ),
          ),
          if (_showEmailChangePopup) _buildEmailChangePopup(),
          if (_showVerificationSuccessPopup) _buildVerificationSuccessPopup(),
        ],
      ),
    );
  }
}