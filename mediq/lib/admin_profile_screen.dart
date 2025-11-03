import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for FilteringTextInputFormatter
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

// --- Global Firebase Configuration (Mandatory) ---
const String __app_id = 'default-app-id';
const String __firebase_config = '{}';
const String __initial_auth_token = '';

// --- Color Palette ---
class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA); // Light Purple for accents
  static const Color lightPurpleBackground = Color(0xFFF3F0FF); // Very light background
  static const Color headerPurple = Color(0xFFE6D6F7); // Header gradient start
  static const Color darkText = Color(0xFF333333);
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);
  static const Color shadowColor = Color(0xFF9F7AEA);
  static const Color inputBorder = Color(0xFFDCDCDC);
}

// --- User Profile Model ---
class UserProfile {
  final String userId;
  final String fullName;
  final String email;
  final String nic;
  final String mobileNumber;
  final String role;
  final String profileImageUrl;
  final DateTime? createdAt;

  UserProfile({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.nic,
    required this.mobileNumber,
    required this.role,
    required this.profileImageUrl,
    this.createdAt,
  });

  factory UserProfile.fromFirestore(String id, Map<String, dynamic> data) {
    return UserProfile(
      userId: id,
      fullName: data['fullName'] ?? 'N/A',
      email: data['email'] ?? 'N/A',
      nic: data['nic'] ?? 'N/A',
      mobileNumber: data['mobileNumber'] ?? 'N/A',
      role: data['role'] ?? 'Administrator',
      profileImageUrl: data['profileImageUrl'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fullName': fullName,
      'email': email,
      'nic': nic,
      'mobileNumber': mobileNumber,
      'role': role,
      'profileImageUrl': profileImageUrl,
    };
  }

  UserProfile copyWith({
    String? fullName,
    String? email,
    String? nic,
    String? mobileNumber,
    String? role,
    String? profileImageUrl,
  }) {
    return UserProfile(
      userId: userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      nic: nic ?? this.nic,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt,
    );
  }
}

// --- Main Screen Widget ---
class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  // --- Firebase Variables ---
  late final FirebaseApp _app;
  late final FirebaseAuth _auth;
  late final FirebaseFirestore _db;
  late final FirebaseStorage _storage;

  String? _userId;
  bool _isInitialized = false;

  // --- Profile Data & Controllers ---
  UserProfile? _userProfile;
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _nicController;
  late TextEditingController _mobileNumberController;

  File? _newProfileImage;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
    _nicController = TextEditingController();
    _mobileNumberController = TextEditingController();
    _initializeFirebase();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _nicController.dispose();
    _mobileNumberController.dispose();
    super.dispose();
  }

  // --- Firebase Initialization and Auth ---

  Future<void> _initializeFirebase() async {
    // Prevent duplicate app initialization
    if (Firebase.apps.isNotEmpty) {
      _app = Firebase.apps.first;
    } else {
      try {
        final firebaseConfig = jsonDecode(__firebase_config) as Map<String, dynamic>;
        final appId = __app_id;

        _app = await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: firebaseConfig['apiKey'] ?? '',
            appId: firebaseConfig['appId'] ?? appId,
            messagingSenderId: firebaseConfig['messagingSenderId'] ?? '',
            projectId: firebaseConfig['projectId'] ?? 'default-project',
            storageBucket: firebaseConfig['storageBucket'],
          ),
        );
      } catch (e) {
        debugPrint("Firebase Initialization Error: $e");
        if (mounted) {
          _showSnackBar('Firebase Initialization Error: ${e.toString()}', isError: true);
        }
        return;
      }
    }

    _auth = FirebaseAuth.instanceFor(app: _app);
    _db = FirebaseFirestore.instanceFor(app: _app);
    _storage = FirebaseStorage.instanceFor(app: _app);

    User? user = _auth.currentUser;
    if (user == null) {
      try {
        if (__initial_auth_token.isNotEmpty) {
          await _auth.signInWithCustomToken(__initial_auth_token);
        } else {
          await _auth.signInAnonymously();
        }
        user = _auth.currentUser;
      } catch (e) {
        debugPrint("Authentication Error: $e");
      }
    }
    
    if (user != null && mounted) {
      setState(() {
        _userId = user!.uid;
        _isInitialized = true;
      });
      _fetchUserProfile();
    }
  }

  // --- Firestore Data Fetching (Real-time) ---

  void _fetchUserProfile() {
    if (_userId == null) return;

    final docRef = _db
        .collection('artifacts')
        .doc(__app_id)
        .collection('users')
        .doc(_userId)
        .collection('user_profiles')
        .doc('profile');

    docRef.snapshots().listen((snapshot) {
      if (snapshot.exists && mounted) {
        final profile = UserProfile.fromFirestore(snapshot.id, snapshot.data()!);
        setState(() {
          _userProfile = profile;
          _fullNameController.text = profile.fullName == 'N/A' ? '' : profile.fullName;
          _emailController.text = profile.email == 'N/A' ? '' : profile.email;
          _nicController.text = profile.nic == 'N/A' ? '' : profile.nic;
          _mobileNumberController.text = profile.mobileNumber == 'N/A' ? '' : profile.mobileNumber;
        });
      } else if (mounted && _userId != null) {
        // Only create default profile if authentication succeeded
        _createDefaultProfile();
      }
    }, onError: (error) {
      debugPrint("Error fetching profile: $error");
      if (mounted) {
        if (error.toString().contains('PERMISSION_DENIED')) {
           _showSnackBar('Profile access denied. Check Firestore security rules.', isError: true);
        } else {
          _showSnackBar('Error fetching profile: $error', isError: true);
        }
      }
    });
  }

  // --- Default Profile Creation ---

  Future<void> _createDefaultProfile() async {
    if (_userId == null) return;
    final defaultData = {
      'fullName': 'Admin User',
      'email': _auth.currentUser?.email ?? 'admin.user@example.com',
      'nic': '999999999V',
      'mobileNumber': '0710000000',
      'role': 'Administrator',
      'profileImageUrl': '',
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await _db
          .collection('artifacts')
          .doc(__app_id)
          .collection('users')
          .doc(_userId)
          .collection('user_profiles')
          .doc('profile')
          .set(defaultData, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error creating default profile: $e");
    }
  }

  // --- Image Picking and Uploading ---

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);

    if (pickedFile != null) {
      setState(() {
        _newProfileImage = File(pickedFile.path);
        _isUpdating = true; // Set uploading state
      });

      try {
        final imageUrl = await _uploadImageToStorage(_newProfileImage!);
        if (imageUrl != null) {
          await _updateFirestoreImageUrl(imageUrl);
          _showSnackBar('Profile Picture Upload Successful.');
        }
      } catch (e) {
        debugPrint("Image Workflow Error: $e");
        _showSnackBar('Profile Picture Upload Failed.', isError: true);
      } finally {
        setState(() {
          _isUpdating = false;
          _newProfileImage = null;
        });
      }
    }
  }

  Future<String?> _uploadImageToStorage(File image) async {
    if (_userId == null) return null;
    try {
      final fileName = 'profile_pic_${_userId!}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = _storage
          .ref()
          .child('artifacts')
          .child(__app_id)
          .child('profile_pictures')
          .child(fileName);

      final uploadTask = storageRef.putFile(image);
      final snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Image Upload Error: $e");
      return null;
    }
  }

  // --- Profile Data Update ---

  Future<void> _updateFirestoreImageUrl(String imageUrl) async {
    if (_userId == null) return;
    try {
      await _db
          .collection('artifacts')
          .doc(__app_id)
          .collection('users')
          .doc(_userId)
          .collection('user_profiles')
          .doc('profile')
          .update({'profileImageUrl': imageUrl});
    } catch (e) {
      debugPrint("Firestore URL Update Error: $e");
      _showSnackBar('Error saving profile picture URL.', isError: true);
    }
  }

  Future<void> _updateProfileData() async {
    if (_userId == null || _userProfile == null || _isUpdating) return;

    // Basic validation
    if (_fullNameController.text.trim().isEmpty) {
      _showSnackBar('Full Name cannot be empty.', isError: true);
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    final updatedProfile = _userProfile!.copyWith(
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      nic: _nicController.text.trim(),
      mobileNumber: _mobileNumberController.text.trim(),
    );

    try {
      await _db
          .collection('artifacts')
          .doc(__app_id)
          .collection('users')
          .doc(_userId)
          .collection('user_profiles')
          .doc('profile')
          .update(updatedProfile.toFirestore());

      _showSnackBar('Profile Data Updated Successfully!');
    } catch (e) {
      debugPrint("Profile Data Update Error: $e");
      _showSnackBar('Profile Data Update Failed.', isError: true);
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  // --- UI Utility ---

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.error : AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // --- Build Methods ---

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _userProfile == null) {
      return const Scaffold(
        backgroundColor: AppColors.lightPurpleBackground,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }

    // Profile Screen Layout
    return Scaffold(
      backgroundColor: AppColors.lightPurpleBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(context),
              _buildBody(),
              const SizedBox(height: 20),
              Text(
                'Developed By Malitha Tishamal',
                style: TextStyle(color: AppColors.darkText.withOpacity(0.6), fontSize: 12),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // Header Section (Profile Picture, Name, Role)
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.headerPurple, Color(0xFFE9D7FD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(color: AppColors.shadowColor, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Functional Back Button
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.darkText, size: 28),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    _showSnackBar('Cannot go back from this screen.');
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.notifications_none, color: AppColors.darkText, size: 28),
                onPressed: () {
                  _showSnackBar('Notifications Tapped');
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildProfileAvatar(),
          const SizedBox(height: 15),
          Text(
            _userProfile!.fullName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.darkText),
          ),
          const SizedBox(height: 4),
          Text(
            _userProfile!.role,
            style: TextStyle(fontSize: 16, color: AppColors.darkText.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  // Profile Avatar (Image Display)
  Widget _buildProfileAvatar() {
    final imageUrl = _userProfile!.profileImageUrl;

    return GestureDetector(
      onTap: _isUpdating ? null : _pickAndUploadImage,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(color: AppColors.shadowColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipOval(
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: 120,
                      height: 120,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.primaryPurple.withOpacity(0.6),
                          child: const Icon(Icons.person, size: 70, color: Colors.white),
                        );
                      },
                    )
                  : Container(
                      color: AppColors.primaryPurple.withOpacity(0.6),
                      child: const Icon(Icons.person, size: 70, color: Colors.white),
                    ),
            ),
            if (_isUpdating)
              const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            
            // Camera icon overlay
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: AppColors.primaryPurple,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Body Section (Input Fields and Update Button)
  Widget _buildBody() {
    final createdAt = _userProfile!.createdAt;
    final formattedDate = createdAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(createdAt) : 'N/A';

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Manage Profile Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText)),
          const Divider(color: AppColors.primaryPurple),

          // We integrate the image picker into the avatar now, so we remove the tile here.
          
          _buildInputField('Full Name', _fullNameController, icon: Icons.person_outline),
          _buildInputField('Email', _emailController, icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, isReadOnly: true),
          _buildInputField('NIC (National Identity Card)', _nicController, icon: Icons.credit_card_outlined),
          _buildInputField('Mobile Number', _mobileNumberController, icon: Icons.phone_outlined, keyboardType: TextInputType.phone, maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),

          const SizedBox(height: 40),

          Center(
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isUpdating ? null : _updateProfileData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 8,
                  shadowColor: AppColors.shadowColor,
                ),
                child: _isUpdating
                    ? const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : const Text('UPDATE PROFILE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ),

          const SizedBox(height: 30),

          Center(
            child: Text(
              'Account Created: $formattedDate (User ID: ${_userId ?? 'N/A'})',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.darkText.withOpacity(0.6), fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // Generic Input Field
  Widget _buildInputField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    IconData? icon,
    int? maxLength,
    bool isReadOnly = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkText)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLength: maxLength,
            readOnly: isReadOnly,
            inputFormatters: inputFormatters,
            style: TextStyle(color: isReadOnly ? AppColors.darkText.withOpacity(0.6) : AppColors.darkText, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              counterText: "", // Hide the default maxLength counter
              prefixIcon: icon != null ? Icon(icon, color: AppColors.primaryPurple.withOpacity(0.7)) : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              fillColor: isReadOnly ? Colors.grey.shade100 : Colors.white,
              filled: true,
              hintText: 'Enter $label',
              hintStyle: TextStyle(color: AppColors.darkText.withOpacity(0.4)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.inputBorder, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.inputBorder, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.error, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
